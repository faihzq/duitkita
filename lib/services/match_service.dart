import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:duitkita/models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache
  List<MatchModel>? _cachedUpcoming;
  List<MatchModel>? _cachedResults;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(hours: 1);

  static const _jdtTeamPageUrl = 'https://www.thesportsdb.com/team/139018';

  // League badge filename -> league name mapping (from TheSportsDB)
  static const _leagueBadgeMap = {
    'laptz91692682937': 'Malaysian Super League',
    'gsbq4k1719686780': 'AFC Champions League Elite',
    'f6w3a61754480776': 'ASEAN Club Championship',
    'vv5p441751132202': 'Malaysian Super League',
  };

  bool get _isCacheValid =>
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  CollectionReference get _matches => _firestore.collection('matches');

  // --- Web Scraping Methods ---

  Future<List<MatchModel>> fetchUpcomingMatches({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid && _cachedUpcoming != null) {
      return _cachedUpcoming!;
    }

    try {
      final scraped = await _scrapeJdtTeamPage();
      final upcoming = scraped['upcoming'] ?? [];

      // Also get manual upcoming matches from Firestore
      final manualMatches = await _fetchManualUpcomingMatches();

      final combined = [...upcoming, ...manualMatches];
      combined.sort((a, b) => a.matchDate.compareTo(b.matchDate));

      _cachedUpcoming = combined;
      _cachedResults = scraped['results'];
      _lastFetchTime = DateTime.now();
      return combined;
    } catch (e) {
      debugPrint('Scraping failed, falling back to Firestore: $e');
      return _fetchManualUpcomingMatches();
    }
  }

  Future<List<MatchModel>> fetchRecentResults({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid && _cachedResults != null) {
      return _cachedResults!;
    }

    try {
      final scraped = await _scrapeJdtTeamPage();
      final results = scraped['results'] ?? [];

      // Also get manual past matches from Firestore
      final manualMatches = await _fetchManualPastMatches();

      final combined = [...results, ...manualMatches];
      combined.sort((a, b) => b.matchDate.compareTo(a.matchDate));

      _cachedUpcoming = scraped['upcoming'];
      _cachedResults = combined;
      _lastFetchTime = DateTime.now();
      return combined;
    } catch (e) {
      debugPrint('Scraping failed, falling back to Firestore: $e');
      return _fetchManualPastMatches();
    }
  }

  /// Scrape TheSportsDB team page to get upcoming matches and results.
  /// Returns a map with 'upcoming' and 'results' lists.
  Future<Map<String, List<MatchModel>>> _scrapeJdtTeamPage() async {
    final response = await http.get(Uri.parse(_jdtTeamPageUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to load JDT page: ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final body = document.body;
    if (body == null) throw Exception('Empty page body');

    final upcoming = <MatchModel>[];
    final results = <MatchModel>[];

    // Find the table containing Upcoming and Results
    // The structure has <b>Upcoming</b> and <b><br>Results</b> headers
    final allTds = body.querySelectorAll('td');

    bool isUpcomingSection = false;
    bool isResultsSection = false;

    // Process TDs in groups of 4 (date, home, center, away)
    final matchRows = <List<dom.Element>>[];
    final matchSections = <String>[];

    List<dom.Element> currentRow = [];

    for (final td in allTds) {
      // Check for section headers
      final boldElements = td.querySelectorAll('b');
      for (final b in boldElements) {
        final text = b.text.trim();
        if (text == 'Upcoming') {
          isUpcomingSection = true;
          isResultsSection = false;
          continue;
        }
        if (text == 'Results') {
          isResultsSection = true;
          isUpcomingSection = false;
          continue;
        }
        // Any other bold text means we've left the matches section
        if (text != 'Upcoming' && text != 'Results' && text.isNotEmpty) {
          if (text == 'Logo') continue; // Skip Logo header
          isUpcomingSection = false;
          isResultsSection = false;
        }
      }

      if (!isUpcomingSection && !isResultsSection) continue;

      // Skip header TDs that contain bold text
      if (boldElements.isNotEmpty) continue;

      // Check if this is a match-related TD (has width attribute)
      final width = td.attributes['width'] ?? '';
      if (width.isEmpty) continue;

      currentRow.add(td);
      if (currentRow.length == 4) {
        matchRows.add(List.from(currentRow));
        matchSections.add(isUpcomingSection ? 'upcoming' : 'results');
        currentRow.clear();
      }
    }

    for (int i = 0; i < matchRows.length; i++) {
      try {
        final row = matchRows[i];
        final section = matchSections[i];
        final match = _parseMatchRow(row, isResult: section == 'results');
        if (match != null) {
          if (section == 'upcoming') {
            upcoming.add(match);
          } else {
            results.add(match);
          }
        }
      } catch (e) {
        debugPrint('Failed to parse match row $i: $e');
      }
    }

    upcoming.sort((a, b) => a.matchDate.compareTo(b.matchDate));
    results.sort((a, b) => b.matchDate.compareTo(a.matchDate));

    return {'upcoming': upcoming, 'results': results};
  }

  /// Parse a single match row from 4 TD elements.
  MatchModel? _parseMatchRow(List<dom.Element> tds, {required bool isResult}) {
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
    String league = 'Malaysian Super League';
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

    // Parse team names from slug (e.g., "penang-vs-johor-darul-tazim")
    final vsParts = slug.split('-vs-');
    String homeTeam;
    String awayTeam;
    if (vsParts.length == 2) {
      homeTeam = _slugToName(vsParts[0]);
      awayTeam = _slugToName(vsParts[1]);
    } else {
      // Fallback to displayed text
      homeTeam = homeLink.text.trim();
      awayTeam = awayLink.text.trim();
    }

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

  /// Convert URL slug to proper name (e.g., "johor-darul-tazim" -> "Johor Darul Tazim")
  String _slugToName(String slug) {
    return slug
        .split('-')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .trim();
  }

  /// Parse date text like "28 Feb" into a DateTime.
  /// For results, dates are in the past. For upcoming, dates are in the future.
  DateTime _parseDateText(String text, {bool isPast = false}) {
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    final parts = text.split(RegExp(r'\s+'));
    if (parts.length < 2) return DateTime.now();

    final day = int.tryParse(parts[0]) ?? 1;
    final monthStr = parts[1].toLowerCase();
    final month = months[monthStr] ?? 1;

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
    final time12Match = RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)', caseSensitive: false)
        .firstMatch(timeText);

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
      final utcTime = DateTime.utc(baseDate.year, baseDate.month, baseDate.day, hour, minute);
      return utcTime.toLocal();
    }

    return baseDate;
  }

  // --- Firestore Methods (Manual Matches) ---

  Future<List<MatchModel>> _fetchManualUpcomingMatches() async {
    final snapshot = await _matches
        .where('matchDate', isGreaterThan: DateTime.now())
        .orderBy('matchDate')
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromFirestoreMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  Future<List<MatchModel>> _fetchManualPastMatches() async {
    final snapshot = await _matches
        .where('matchDate', isLessThanOrEqualTo: DateTime.now())
        .orderBy('matchDate', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromFirestoreMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
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
    _cachedUpcoming = null;
    _cachedResults = null;
    _lastFetchTime = null;
  }
}

// Providers
final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService();
});

final upcomingMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  final matchService = ref.watch(matchServiceProvider);
  return matchService.fetchUpcomingMatches();
});

final recentResultsProvider = FutureProvider<List<MatchModel>>((ref) async {
  final matchService = ref.watch(matchServiceProvider);
  return matchService.fetchRecentResults();
});
