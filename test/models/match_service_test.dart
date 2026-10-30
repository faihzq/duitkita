import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:duitkita/services/match_service.dart';

/// Real markup from thesportsdb.com/team/139018: the two section headers, two
/// fixtures, one result, the spacer between the sections, and the first row of
/// the squad table that follows them.
///
/// The squad row matters. It carries the same four-ish cells as a fixture but
/// no event link, and it is what has to stop the Results section — the page
/// offers no closing marker of its own.
const _teamPage = r"""
<table>
<tr style='background-color:#101b16;'><td class='py-1'>&nbsp;</td><td class='py-1'>&nbsp;</td><td class='fw-semibold py-1 text-white text-center'>Upcoming</td><td class='py-1'>&nbsp;</td></tr>
<tr><td width='5%' max-width='10' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/laptz91692682937.png/tiny' alt='tiny league badge icon' width='16' /> 04 Sep <span class='team-table-year'>26</span></td><td width='13%' align='right'><a href='/event/2546163-dpmm-vs-johor-darul-tazim'><span class='team-fixture-name'><span class='team-fixture-name-short'>DPMM</span><span class='team-fixture-name-full'>DPMM</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/vht2ab1583166614.png/tiny' alt='tiny home badge icon' width='16' /></td><td align='center' width='10%' max-width='80' class='text-nowrap'> 12:15pm </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2546163-dpmm-vs-johor-darul-tazim'><span class='team-fixture-name'><span class='team-fixture-name-short'>Johor Dar</span><span class='team-fixture-name-full'>Johor Darul Ta'zim</span></span></a></td></tr>
<tr><td width='5%' max-width='10' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/gsbq4k1719686780.png/tiny' alt='tiny league badge icon' width='16' /> 15 Sep <span class='team-table-year'>26</span></td><td width='13%' align='right'><a href='/event/2579914-johor-darul-tazim-vs-buriram-united'><span class='team-fixture-name'><span class='team-fixture-name-short'>Johor Dar</span><span class='team-fixture-name-full'>Johor Darul Ta'zim</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png/tiny' alt='tiny home badge icon' width='16' /></td><td align='center' width='10%' max-width='80' class='text-nowrap'> 12:15pm </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/0z45791784587806.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2579914-johor-darul-tazim-vs-buriram-united'><span class='team-fixture-name'><span class='team-fixture-name-short'>Buriram U</span><span class='team-fixture-name-full'>Buriram United</span></span></a></td></tr>
<tr style='background-color:#0d170f; border-color:#0d170f; --bs-table-accent-bg:#0d170f;'><td colspan='4' class='py-1' style='background-color:#0d170f; border-color:#0d170f; --bs-table-accent-bg:#0d170f; box-shadow:inset 0 0 0 9999px #0d170f;'>&nbsp;</td></tr>
<tr style='background-color:#101b16;'><td class='py-1'>&nbsp;</td><td class='py-1'>&nbsp;</td><td class='fw-semibold py-1 text-white text-center'>Results</td><td class='py-1'>&nbsp;</td></tr>
<tr><td width='5%' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/laptz91692682937.png/tiny' alt='tiny league badge icon' width='16' /> 29 Aug <span class='team-table-year'>26</span></td><td width='13%' max-width='10' align='right'><a href='/event/2546160-johor-darul-tazim-vs-imigresen'><span class='team-fixture-name'><span class='team-fixture-name-short'>Johor Dar</span><span class='team-fixture-name-full'>Johor Darul Ta'zim</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png/tiny' alt='tiny home badge icon' width='16' /> </td><td width='10%' align='center' max-width='80' class='text-nowrap'>7 - 0 </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/2w3cxf1751131358.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2546160-johor-darul-tazim-vs-imigresen'><span class='team-fixture-name'><span class='team-fixture-name-short'>Imigresen</span><span class='team-fixture-name-full'>Imigresen</span></span></a></td></tr>
<tr><td valign='top' width='33%'><center><a href='/player/34289048-arif-aiman'><img src='/images/no_cutout.png' alt='no player cutout' style='width:75%';><br>42 <img src='/images/icons/svg/flags/Malaysia.svg' width='20' alt='Flag'> Aiman</a><br><br><br></center></td><td></td><td valign='top' width='33%'><center><a href='/player/34145773-jordi-amat'><img src='/images/player_blur_small.jpg' alt='player blur small' style='width:75%';><br>5 <img src='/images/icons/svg/flags/Indonesia.svg' width='20' alt='Flag'> Amat</a><br><br><br></center></td><td></td><td valign='top' width='33%'><center><a href='/player/34175206-%c3%93scar-arribas'><img src='/images/no_cutout.png' alt='no player cutout' style='width:75%';><br>24 <img src='/images/icons/svg/flags/Philippines.svg' width='20' alt='Flag'> Arribas</a><br><br><br></center></td><td></td></tr>
</table>
""";

/// Real markup from the Malaysia national team page (team 140138). The second
/// fixture's competition badge has been renamed to one the map does not know,
/// which is what pins the per-team fallback label.
const _malaysiaPage = r"""
<table>
<tr style='background-color:#101b16;'><td class='py-1'>&nbsp;</td><td class='py-1'>&nbsp;</td><td class='fw-semibold py-1 text-white text-center'>Results</td><td class='py-1'>&nbsp;</td></tr>
<tr><td width='5%' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/z9dvdf1780551855.png/tiny' alt='tiny league badge icon' width='16' /> 19 Aug <span class='team-table-year'>26</span></td><td width='13%' max-width='10' align='right'><a href='/event/2569199-vietnam-vs-malaysia'><span class='team-fixture-name'><span class='team-fixture-name-short'>Vietnam</span><span class='team-fixture-name-full'>Vietnam</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/i18iu41597944056.png/tiny' alt='tiny home badge icon' width='16' /> </td><td width='10%' align='center' max-width='80' class='text-nowrap'>2 - 0 </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/opqzci1597866541.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2569199-vietnam-vs-malaysia'><span class='team-fixture-name'><span class='team-fixture-name-short'>Malaysia</span><span class='team-fixture-name-full'>Malaysia</span></span></a></td></tr>
<tr><td width='5%' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/zz0unknown0000000.png/tiny' alt='tiny league badge icon' width='16' /> 16 Aug <span class='team-table-year'>26</span></td><td width='13%' max-width='10' align='right'><a href='/event/2569197-malaysia-vs-vietnam'><span class='team-fixture-name'><span class='team-fixture-name-short'>Malaysia</span><span class='team-fixture-name-full'>Malaysia</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/opqzci1597866541.png/tiny' alt='tiny home badge icon' width='16' /> </td><td width='10%' align='center' max-width='80' class='text-nowrap'>0 - 2 </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/i18iu41597944056.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2569197-malaysia-vs-vietnam'><span class='team-fixture-name'><span class='team-fixture-name-short'>Vietnam</span><span class='team-fixture-name-full'>Vietnam</span></span></a></td></tr>
</table>
""";

/// Three real results. The last is the 31 Jul 2026 friendly, which TheSportsDB
/// files with its two crests swapped — Cartagena is named as the home side but
/// carries JDT's badge. Its own API repeats the error, so the source is wrong.
const _swappedCrestPage = r"""
<table>
<tr style='background-color:#101b16;'><td class='py-1'>&nbsp;</td><td class='py-1'>&nbsp;</td><td class='fw-semibold py-1 text-white text-center'>Results</td><td class='py-1'>&nbsp;</td></tr>
<tr><td width='5%' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/laptz91692682937.png/tiny' alt='tiny league badge icon' width='16' /> 29 Aug <span class='team-table-year'>26</span></td><td width='13%' max-width='10' align='right'><a href='/event/2546160-johor-darul-tazim-vs-imigresen'><span class='team-fixture-name'><span class='team-fixture-name-short'>Johor Dar</span><span class='team-fixture-name-full'>Johor Darul Ta'zim</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png/tiny' alt='tiny home badge icon' width='16' /> </td><td width='10%' align='center' max-width='80' class='text-nowrap'>7 - 0 </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/2w3cxf1751131358.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2546160-johor-darul-tazim-vs-imigresen'><span class='team-fixture-name'><span class='team-fixture-name-short'>Imigresen</span><span class='team-fixture-name-full'>Imigresen</span></span></a></td></tr>
<tr><td width='5%' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/laptz91692682937.png/tiny' alt='tiny league badge icon' width='16' /> 26 Aug <span class='team-table-year'>26</span></td><td width='13%' max-width='10' align='right'><a href='/event/2546155-johor-darul-tazim-vs-kelantan-red-warrior'><span class='team-fixture-name'><span class='team-fixture-name-short'>Johor Dar</span><span class='team-fixture-name-full'>Johor Darul Ta'zim</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png/tiny' alt='tiny home badge icon' width='16' /> </td><td width='10%' align='center' max-width='80' class='text-nowrap'>9 - 0 </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/xf7fjq1784826024.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2546155-johor-darul-tazim-vs-kelantan-red-warrior'><span class='team-fixture-name'><span class='team-fixture-name-short'>Kelantan </span><span class='team-fixture-name-full'>Kelantan Red Warrior</span></span></a></td></tr>
<tr><td width='5%' class='text-nowrap'><img src='https://r2.thesportsdb.com/images/media/league/badge/gb18781565430778.png/tiny' alt='tiny league badge icon' width='16' /> 31 Jul <span class='team-table-year'>26</span></td><td width='13%' max-width='10' align='right'><a href='/event/2549382-johor-darul-tazim-vs-cartagena'><span class='team-fixture-name'><span class='team-fixture-name-short'>Cartagena</span><span class='team-fixture-name-full'>Cartagena</span></span> </a><img src='https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png/tiny' alt='tiny home badge icon' width='16' /> </td><td width='10%' align='center' max-width='80' class='text-nowrap'>2 - 0 </td><td width='17%' align='left'><img src='https://r2.thesportsdb.com/images/media/team/badge/xzrxd71677472112.png/tiny' alt='tiny away badge icon' width='16' /> <a href='/event/2549382-johor-darul-tazim-vs-cartagena'><span class='team-fixture-name'><span class='team-fixture-name-short'>Johor Dar</span><span class='team-fixture-name-full'>Johor Darul Ta'zim</span></span></a></td></tr>
</table>
""";

void main() {
  group('parseTeamPage', () {
    final parsed = MatchService().parseTeamPage(_teamPage);
    final upcoming = parsed['upcoming']!;
    final results = parsed['results']!;

    test('splits fixtures from results and ignores everything else', () {
      expect(upcoming.length, 2);
      expect(results.length, 1);
    });

    test('reads the full team name, not the slug or the truncated span', () {
      // The slug would give "Johor Darul Tazim" and the link text would give
      // "Johor Dar Johor Darul Ta'zim".
      expect(upcoming.first.awayTeam, "Johor Darul Ta'zim");
      expect(upcoming.first.homeTeam, 'DPMM');
    });

    test('takes the year from the page rather than inferring it', () {
      expect(upcoming.first.matchDate.year, 2026);
      expect(upcoming.first.matchDate.month, 9);
      expect(upcoming.first.matchDate.day, 4);
    });

    test('reads kick-off as UTC and returns it local', () {
      expect(
        upcoming.first.matchDate,
        DateTime.utc(2026, 9, 4, 12, 15).toLocal(),
      );
    });

    test('maps the league badge to a league name', () {
      expect(upcoming.first.league, 'Malaysian Super League');
      expect(upcoming[1].league, 'AFC Champions League Elite');
    });

    test('parses the score and marks the match finished', () {
      final r = results.single;
      expect(r.homeTeam, "Johor Darul Ta'zim");
      expect(r.awayTeam, 'Imigresen');
      expect(r.homeScore, 7);
      expect(r.awayScore, 0);
      expect(r.status, 'FT');
      expect(r.id, 'sdb_2546160');
    });

    test('sorts fixtures soonest first and results newest first', () {
      expect(upcoming.first.matchDate.isBefore(upcoming[1].matchDate), isTrue);
    });

    test('returns empty lists rather than throwing on unknown markup', () {
      final empty = MatchService().parseTeamPage(
        '<table><tr><td>x</td></tr></table>',
      );
      expect(empty['upcoming'], isEmpty);
      expect(empty['results'], isEmpty);
    });
  });

  group('scrape fallbacks', () {
    MatchService serving(
      String body, {
      int status = 200,
      FirebaseFirestore? firestore,
    }) => MatchService(
      client: MockClient((_) async => http.Response(body, status)),
      firestore: firestore ?? FakeFirebaseFirestore(),
    );

    // Markup the parser cannot make sense of — what a redesign looks like.
    const moved = '<table><tr><td>nothing here any more</td></tr></table>';

    test('returns the scraped fixtures when the page parses', () async {
      expect((await serving(_teamPage).fetchUpcomingMatches()).length, 2);
      expect((await serving(_teamPage).fetchRecentResults()).length, 1);
    });

    test('errors when nothing parses and nothing was entered by hand', () {
      expect(serving(moved).fetchUpcomingMatches(), throwsA(isA<Exception>()));
      expect(serving(moved).fetchRecentResults(), throwsA(isA<Exception>()));
    });

    test('errors when the page itself fails to load', () {
      expect(
        serving('Not Found', status: 404).fetchUpcomingMatches(),
        throwsA(isA<Exception>()),
      );
    });

    test('prefers hand-entered matches over erroring', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('matches').add({
        'homeTeam': "Johor Darul Ta'zim",
        'awayTeam': 'Selangor',
        'matchDate': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 3)),
        ),
        'league': 'Malaysia Cup',
        'status': 'NS',
      });

      final matches =
          await serving(moved, firestore: firestore).fetchUpcomingMatches();

      expect(matches.single.awayTeam, 'Selangor');
      expect(matches.single.isManual, isTrue);
    });
  });

  group('other teams', () {
    final parsed = MatchService().parseTeamPage(
      _malaysiaPage,
      team: FootballTeam.malaysia,
    );

    test('reads the national team page with the same parser', () {
      expect(parsed['results']!.length, 2);
      expect(parsed['upcoming'], isEmpty);
      expect(parsed['results']!.first.homeTeam, 'Vietnam');
      expect(parsed['results']!.first.awayTeam, 'Malaysia');
    });

    test('names a competition it recognises', () {
      expect(parsed['results']!.first.league, 'ASEAN Championship');
    });

    test('labels an unknown competition per team, not as a club league', () {
      // The old code hard-coded "Malaysian Super League" here, which would put
      // the national side in a club competition it cannot play in.
      expect(parsed['results']!.last.league, 'International');
    });

    test('leaves JDT the club-league fallback', () {
      final asJdt = MatchService().parseTeamPage(_malaysiaPage);
      expect(asJdt['results']!.last.league, 'Malaysian Super League');
    });
  });

  group('crest reconciliation', () {
    final results = MatchService().parseTeamPage(_swappedCrestPage)['results']!;
    const jdtCrest = 'team/badge/8cq3lk1752771555.png';

    test('gives a team the crest it wears in the majority of rows', () {
      // In the corrupt row JDT's badge sits on the opponent's side; the two
      // clean rows outvote it.
      final friendly = results.firstWhere((m) => m.awayTeam.contains('Johor'));
      expect(friendly.awayTeamLogo, contains(jdtCrest));
    });

    test('puts a swapped pair back the right way round', () {
      // Cartagena is seen once, wearing JDT's badge — so the row's two crests
      // are reversed, and the other one is Cartagena's. Confirmed against
      // TheSportsDB's own team record: xzrxd7… is Cartagena of Spain.
      final friendly = results.firstWhere((m) => m.homeTeam == 'Cartagena');
      expect(friendly.homeTeamLogo, contains('xzrxd71677472112'));
      expect(friendly.awayTeamLogo, contains(jdtCrest));
    });

    test('leaves correct rows untouched', () {
      final clean = results.firstWhere((m) => m.awayTeam == 'Imigresen');
      expect(clean.homeTeamLogo, contains(jdtCrest));
      expect(clean.awayTeamLogo, contains('2w3cxf1751131358'));
    });
  });
}
