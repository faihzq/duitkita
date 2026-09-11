import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:duitkita/models/match_model.dart';

/// The teams the app follows.
///
/// Both render from the same team-page markup, so following another side is a
/// matter of its id. [fallbackLeague] is what an unrecognised competition badge
/// is labelled as — a club's domestic league, a national side's internationals.
enum FootballTeam {
  jdt(
    '139018',
    'JDT',
    'Malaysian Super League',
    crestUrl:
        'https://r2.thesportsdb.com/images/media/team/badge/8cq3lk1752771555.png',
    crestAsset: 'assets/images/jdt_crest.png',
  ),
  malaysia(
    '140138',
    'Malaysia',
    'International',
    crestUrl:
        'https://r2.thesportsdb.com/images/media/team/badge/opqzci1597866541.png',
    crestAsset: 'assets/images/malaysia_crest.png',
  );

  const FootballTeam(
    this.id,
    this.label,
    this.fallbackLeague, {
    required this.crestUrl,
    required this.crestAsset,
  });

  final String id;
  final String label;
  final String fallbackLeague;

  /// The bundled crest, 512x512 — the header paints it on the first frame and
  /// it survives being offline. The app previously shipped a 96x120 JDT logo,
  /// which was visibly soft once scaled up.
  final String crestAsset;

  /// Where [crestAsset] came from, kept as the fallback and as the record of
  /// what to re-download when a club changes its crest.
  final String crestUrl;

  String get pageUrl => 'https://www.thesportsdb.com/team/$id';
}

class MatchService {
  /// Both dependencies are injectable so the fallback rules — when a failed
  /// scrape is covered by hand-entered matches and when it surfaces as an
  /// error — can be exercised without a network or a Firebase app.
  MatchService({http.Client? client, FirebaseFirestore? firestore})
    : _client = client ?? http.Client(),
      _injectedFirestore = firestore;

  final http.Client _client;
  final FirebaseFirestore? _injectedFirestore;

  // Lazy: parsing the team page touches no Firestore, and resolving
  // `instance` eagerly would demand an initialised Firebase app to do it.
  late final FirebaseFirestore _firestore =
      _injectedFirestore ?? FirebaseFirestore.instance;

  // In-memory cache, one entry per team.
  final Map<FootballTeam, List<MatchModel>> _cachedUpcoming = {};
  final Map<FootballTeam, List<MatchModel>> _cachedResults = {};
  final Map<FootballTeam, DateTime> _lastFetchTime = {};
  static const _cacheDuration = Duration(hours: 1);

  // League badge filename -> league name mapping (from TheSportsDB)
  static const _leagueBadgeMap = {
    'laptz91692682937': 'Malaysian Super League',
    'gsbq4k1719686780': 'AFC Champions League Elite',
    'f6w3a61754480776': 'ASEAN Club Championship',
    'vv5p441751132202': 'Malaysian Super League',
    'z9dvdf1780551855': 'ASEAN Championship',
  };

  bool _isCacheValid(FootballTeam team) {
    final fetchedAt = _lastFetchTime[team];
    return fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _cacheDuration;
  }

  CollectionReference get _matches => _firestore.collection('matches');

  // --- Web Scraping Methods ---

  Future<List<MatchModel>> fetchUpcomingMatches({
    FootballTeam team = FootballTeam.jdt,
    bool forceRefresh = false,
  }) async {
    final cached = _cachedUpcoming[team];
    if (!forceRefresh && _isCacheValid(team) && cached != null) {
      return cached;
    }

    try {
      final scraped = await _scrapeTeamPage(team);
      final upcoming = scraped['upcoming'] ?? [];

      // Hand-entered matches are JDT's only; the national side has no manual
      // equivalent, and mixing them into another team's list would be wrong.
      final manualMatches =
          team == FootballTeam.jdt
              ? await _fetchManualUpcomingMatches()
              : <MatchModel>[];

      final combined = [...upcoming, ...manualMatches];
      combined.sort((a, b) => a.matchDate.compareTo(b.matchDate));

      _cachedUpcoming[team] = combined;
      _cachedResults[team] = scraped['results'] ?? [];
      _lastFetchTime[team] = DateTime.now();
      return combined;
    } catch (e) {
      debugPrint('Scraping failed, falling back to Firestore: $e');
      // Hand-entered matches still stand in for the scrape. Only when there are
      // none either does the failure reach the UI, which shows a retry rather
      // than an empty list indistinguishable from a quiet week.
      final manual =
          team == FootballTeam.jdt
              ? await _fetchManualUpcomingMatches()
              : <MatchModel>[];
      if (manual.isEmpty) rethrow;
      return manual;
    }
  }

  Future<List<MatchModel>> fetchRecentResults({
    FootballTeam team = FootballTeam.jdt,
    bool forceRefresh = false,
  }) async {
    final cached = _cachedResults[team];
    if (!forceRefresh && _isCacheValid(team) && cached != null) {
      return cached;
    }

    try {
      final scraped = await _scrapeTeamPage(team);
      final results = scraped['results'] ?? [];

      final manualMatches =
          team == FootballTeam.jdt
              ? await _fetchManualPastMatches()
              : <MatchModel>[];

      final combined = [...results, ...manualMatches];
      combined.sort((a, b) => b.matchDate.compareTo(a.matchDate));

      _cachedUpcoming[team] = scraped['upcoming'] ?? [];
      _cachedResults[team] = combined;
      _lastFetchTime[team] = DateTime.now();
      return combined;
    } catch (e) {
      debugPrint('Scraping failed, falling back to Firestore: $e');
      final manual =
          team == FootballTeam.jdt
              ? await _fetchManualPastMatches()
              : <MatchModel>[];
      if (manual.isEmpty) rethrow;
      return manual;
    }
  }

  /// Scrape TheSportsDB team page to get upcoming matches and results.
  /// Returns a map with 'upcoming' and 'results' lists.
  Future<Map<String, List<MatchModel>>> _scrapeTeamPage(
    FootballTeam team,
  ) async {
    final response = await _client.get(Uri.parse(team.pageUrl));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load the ${team.label} page: ${response.statusCode}',
      );
    }

    final parsed = parseTeamPage(response.body, team: team);

    // A live page always lists something: the club plays in four competitions
    // and the Results section keeps the last five whatever the calendar says.
    // Parsing nothing out of a 200 means the markup moved again, and returning
    // empty lists would render that as "No upcoming matches" and cache it for
    // an hour — which is exactly how the last change went unnoticed.
    if (parsed['upcoming']!.isEmpty && parsed['results']!.isEmpty) {
      throw Exception(
        'Parsed no matches from the ${team.label} page: markup changed?',
      );
    }
    return parsed;
  }

  /// The HTML half of [_scrapeTeamPage], split out so a fixture can pin it.
  /// The site's markup is not a contract and has changed under us before,
  /// silently emptying both lists rather than failing.
  @visibleForTesting
  Map<String, List<MatchModel>> parseTeamPage(
    String html, {
    FootballTeam team = FootballTeam.jdt,
  }) {
    final document = html_parser.parse(html);
    final body = document.body;
    if (body == null) throw Exception('Empty page body');

    final upcoming = <MatchModel>[];
    final results = <MatchModel>[];

    // Each section starts with a header row whose middle cell reads "Upcoming"
    // or "Results"; every fixture below it is one row of four cells — date,
    // home, kick-off or score, away.
    //
    // Walk rows rather than a flat list of cells. The site used to wrap those
    // two headers in <b>, and the old scan keyed off that; it now renders them
    // as plain styled cells, so nothing ever switched the section on and no
    // fixture was ever collected. A row is a fixture if it links to an event,
    // which also ends the Results section on its own: the spacer row and the
    // squad table that follow carry no such link.
    String? section;
    for (final row in body.querySelectorAll('tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.isEmpty) continue;

      final heading = cells
          .map((c) => c.text.trim())
          .firstWhere(
            (t) => t == 'Upcoming' || t == 'Results',
            orElse: () => '',
          );
      if (heading.isNotEmpty) {
        section = heading == 'Upcoming' ? 'upcoming' : 'results';
        continue;
      }

      if (section == null || cells.length != 4) continue;
      if (row.querySelector('a[href*="/event/"]') == null) continue;

      final isResult = section == 'results';
      try {
        final match = _parseMatchRow(cells, isResult: isResult, team: team);
        if (match != null) (isResult ? results : upcoming).add(match);
      } catch (e) {
        debugPrint('Failed to parse match row: $e');
      }
    }

    upcoming.sort((a, b) => a.matchDate.compareTo(b.matchDate));
    results.sort((a, b) => b.matchDate.compareTo(a.matchDate));

    // Vote across both lists at once — more rows, better evidence.
    final crests = _canonicalCrests([...upcoming, ...results]);

    return {
      'upcoming': [for (final m in upcoming) _withCrests(m, crests)],
      'results': [for (final m in results) _withCrests(m, crests)],
    };
  }

  /// Parse a single match row from 4 TD elements.
  MatchModel? _parseMatchRow(
    List<dom.Element> tds, {
    required bool isResult,
    required FootballTeam team,
  }) {
    if (tds.length < 4) return null;

    final dateTd = tds[0];
    final homeTd = tds[1];
    final centerTd = tds[2];
    final awayTd = tds[3];

    // Extract date string (e.g., "28 Feb")
    final dateText = dateTd.text.trim();

    // Extract league name from the league badge image in the date TD
    // Badge URLs look like: .../league/badge/laptz91692682937.png/tiny
    final leagueBadgeImg = dateTd.querySelector('img[alt*="league"]');
    final leagueBadgeSrc = leagueBadgeImg?.attributes['src'] ?? '';
    // An unrecognised badge means a competition not in the map — label it with
    // the team's usual stage rather than asserting a league it may not be in.
    String league = team.fallbackLeague;
    for (final entry in _leagueBadgeMap.entries) {
      if (leagueBadgeSrc.contains(entry.key)) {
        league = entry.value;
        break;
      }
    }

    // Extract event ID and full team names from the event URL
    final homeLink = homeTd.querySelector('a');
    final awayLink = awayTd.querySelector('a');
    if (homeLink == null || awayLink == null) return null;

    final eventHref = homeLink.attributes['href'] ?? '';
    final eventIdMatch = RegExp(r'/event/(\d+)-(.+)').firstMatch(eventHref);
    if (eventIdMatch == null) return null;

    final eventId = eventIdMatch.group(1)!;
    final slug = eventIdMatch.group(2)!;

    // Each cell renders the name twice, abbreviated and full. Read the full
    // one: the link text concatenates both ("Johor Dar Johor Darul Ta'zim"),
    // and the slug fallback loses punctuation ("Johor Darul Tazim").
    final vsParts = slug.split('-vs-');
    final homeTeam =
        _fixtureName(homeTd) ??
        (vsParts.length == 2 ? _slugToName(vsParts[0]) : homeLink.text.trim());
    final awayTeam =
        _fixtureName(awayTd) ??
        (vsParts.length == 2 ? _slugToName(vsParts[1]) : awayLink.text.trim());

    // Extract team badge URLs
    final homeBadgeImg = homeTd.querySelector('img[alt*="badge"]');
    final awayBadgeImg = awayTd.querySelector('img[alt*="badge"]');
    final homeBadge = homeBadgeImg?.attributes['src']?.replaceAll('/tiny', '');
    final awayBadge = awayBadgeImg?.attributes['src']?.replaceAll('/tiny', '');

    // Parse center column (time for upcoming, score for results)
    final centerText = centerTd.text.trim();

    int? homeScore;
    int? awayScore;
    String status = 'NS';
    DateTime matchDate;

    if (isResult) {
      // Parse score like "1 - 6"
      final scoreMatch = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(centerText);
      if (scoreMatch != null) {
        homeScore = int.tryParse(scoreMatch.group(1)!);
        awayScore = int.tryParse(scoreMatch.group(2)!);
      }
      status = 'FT';
      matchDate = _parseDateText(dateText, isPast: true);
    } else {
      // Parse time like "2:00pm"
      matchDate = _parseDateTimeText(dateText, centerText);
    }

    return MatchModel(
      id: 'sdb_$eventId',
      homeTeam: homeTeam,
      homeTeamLogo: homeBadge,
      awayTeam: awayTeam,
      awayTeamLogo: awayBadge,
      matchDate: matchDate,
      league: league,
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }

  /// The name as the page renders it, or null when the cell has no full-name
  /// span for the caller to fall back from.
  String? _fixtureName(dom.Element td) {
    final full = td.querySelector('.team-fixture-name-full')?.text.trim();
    return (full == null || full.isEmpty) ? null : full;
  }

  /// The crest each team actually wears, decided by majority across every row.
  ///
  /// The source occasionally files an event with its two badges swapped: the
  /// 31 Jul 2026 friendly names Cartagena as the home side but carries JDT's
  /// crest there, and TheSportsDB's own API repeats the mistake, so it is the
  /// data that is wrong rather than the parse. A club wears one crest in every
  /// row it appears in, so the badge seen most often against a name is the
  /// right one. Voting rather than hard-coding also survives a club changing
  /// its crest — the filename carries a timestamp — since the new image simply
  /// becomes the new majority.
  ///
  /// A team seen once contributes no evidence and is left out.
  Map<String, String> _canonicalCrests(List<MatchModel> matches) {
    final tally = <String, Map<String, int>>{};
    void count(String team, String? badge) {
      if (badge == null || badge.isEmpty) return;
      (tally[team] ??= {}).update(badge, (n) => n + 1, ifAbsent: () => 1);
    }

    for (final match in matches) {
      count(match.homeTeam, match.homeTeamLogo);
      count(match.awayTeam, match.awayTeamLogo);
    }

    final canonical = <String, String>{};
    tally.forEach((team, badges) {
      final best = badges.entries.reduce((a, b) => b.value > a.value ? b : a);
      if (best.value > 1) canonical[team] = best.key;
    });
    return canonical;
  }

  MatchModel _withCrests(MatchModel match, Map<String, String> crests) {
    final taken = crests.values.toSet();

    /// [otherBadge] is the crest on the other side of the same fixture.
    ///
    /// A team with an established crest simply gets it. A team seen only once
    /// has none to fall back on, so its badge is taken at face value — unless
    /// that badge demonstrably belongs to somebody else, which means the row's
    /// two crests are the wrong way round. A row shows exactly two teams, so
    /// the other badge is then this team's: swapping recovers both rather than
    /// leaving one blank.
    String? resolve(String team, String? badge, String? otherBadge) {
      final own = crests[team];
      if (own != null) return own;
      if (badge != null && taken.contains(badge)) {
        final swapped = otherBadge != null && !taken.contains(otherBadge);
        return swapped ? otherBadge : null;
      }
      return badge;
    }

    final home = resolve(
      match.homeTeam,
      match.homeTeamLogo,
      match.awayTeamLogo,
    );
    final away = resolve(
      match.awayTeam,
      match.awayTeamLogo,
      match.homeTeamLogo,
    );
    if (home == match.homeTeamLogo && away == match.awayTeamLogo) return match;

    return MatchModel(
      id: match.id,
      homeTeam: match.homeTeam,
      homeTeamLogo: home,
      awayTeam: match.awayTeam,
      awayTeamLogo: away,
      matchDate: match.matchDate,
      venue: match.venue,
      league: match.league,
      status: match.status,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      isManual: match.isManual,
    );
  }

  /// Convert URL slug to proper name (e.g., "johor-darul-tazim" -> "Johor Darul Tazim")
  String _slugToName(String slug) {
    return slug
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .trim();
  }

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Parse date text like "28 Feb" or "04 Sep 26" into a DateTime.
  ///
  /// The cell now carries a two-digit year of its own, so use it when present.
  /// The guesswork below only runs for markup that omits it, and it gets a
  /// December fixture read in January wrong by a year either way.
  DateTime _parseDateText(String text, {bool isPast = false}) {
    final parsed = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3,})\.?\s*(\d{2})?',
    ).firstMatch(text);
    if (parsed == null) return DateTime.now();

    final day = int.tryParse(parsed.group(1)!) ?? 1;
    final month = _months[parsed.group(2)!.toLowerCase().substring(0, 3)] ?? 1;

    final explicitYear = parsed.group(3);
    if (explicitYear != null) {
      return DateTime(2000 + int.parse(explicitYear), month, day);
    }

    final now = DateTime.now();
    int year = now.year;

    // For past dates, if the date would be in the future, use previous year
    if (isPast) {
      final candidate = DateTime(year, month, day);
      if (candidate.isAfter(now)) year--;
    } else {
      // For upcoming dates, if the date would be in the past, use next year
      final candidate = DateTime(year, month, day);
      if (candidate.isBefore(now.subtract(const Duration(days: 1)))) year++;
    }

    return DateTime(year, month, day);
  }

  /// Parse date + time text into a local DateTime.
  /// Times from the website are in UTC — convert to local (MYT = UTC+8).
  DateTime _parseDateTimeText(String dateText, String timeText) {
    final baseDate = _parseDateText(dateText, isPast: false);

    int? hour;
    int? minute;

    // Try 12h format first: "2:00pm", "8:15pm", "12:15am"
    final time12Match = RegExp(
      r'(\d{1,2}):(\d{2})\s*(am|pm)',
      caseSensitive: false,
    ).firstMatch(timeText);

    if (time12Match != null) {
      hour = int.parse(time12Match.group(1)!);
      minute = int.parse(time12Match.group(2)!);
      final period = time12Match.group(3)!.toLowerCase();

      if (period == 'pm' && hour != 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
    } else {
      // Try 24h format: "20:15", "04:15", "14:00"
      final time24Match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeText);
      if (time24Match != null) {
        hour = int.parse(time24Match.group(1)!);
        minute = int.parse(time24Match.group(2)!);
      }
    }

    if (hour != null && minute != null) {
      // Website times are UTC — create as UTC then convert to local
      final utcTime = DateTime.utc(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
      return utcTime.toLocal();
    }

    return baseDate;
  }

  // --- Firestore Methods (Manual Matches) ---

  Future<List<MatchModel>> _fetchManualUpcomingMatches() async {
    final snapshot =
        await _matches
            .where('matchDate', isGreaterThan: DateTime.now())
            .orderBy('matchDate')
            .get();

    return snapshot.docs
        .map(
          (doc) => MatchModel.fromFirestoreMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<List<MatchModel>> _fetchManualPastMatches() async {
    final snapshot =
        await _matches
            .where('matchDate', isLessThanOrEqualTo: DateTime.now())
            .orderBy('matchDate', descending: true)
            .limit(10)
            .get();

    return snapshot.docs
        .map(
          (doc) => MatchModel.fromFirestoreMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<void> addManualMatch({
    required String homeTeam,
    required String awayTeam,
    required DateTime matchDate,
    String? venue,
    String league = 'Malaysia Super League',
  }) async {
    try {
      await _matches.add({
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'matchDate': matchDate,
        'venue': venue,
        'league': league,
        'status': 'NS',
        'homeScore': null,
        'awayScore': null,
        'homeTeamLogo': null,
        'awayTeamLogo': null,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to add match: $e');
    }
  }

  Future<void> deleteManualMatch(String matchId) async {
    try {
      await _matches.doc(matchId).delete();
    } catch (e) {
      throw Exception('Failed to delete match: $e');
    }
  }

  void clearCache() {
    _cachedUpcoming.clear();
    _cachedResults.clear();
    _lastFetchTime.clear();
  }
}

// Providers
final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService();
});

final upcomingMatchesProvider =
    FutureProvider.family<List<MatchModel>, FootballTeam>((ref, team) async {
      final matchService = ref.watch(matchServiceProvider);
      return matchService.fetchUpcomingMatches(team: team);
    });

final recentResultsProvider =
    FutureProvider.family<List<MatchModel>, FootballTeam>((ref, team) async {
      final matchService = ref.watch(matchServiceProvider);
      return matchService.fetchRecentResults(team: team);
    });
